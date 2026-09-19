package com.tareasapp.mobile.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.tareasapp.mobile.data.model.Task
import com.tareasapp.mobile.data.remote.RetrofitClient
import com.tareasapp.mobile.data.repository.ApiResult
import com.tareasapp.mobile.data.repository.TaskRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed class TaskUiEvent {
    object Loading : TaskUiEvent()
    data class Loaded(val tasks: List<Task>) : TaskUiEvent()
    data class Failed(val message: String) : TaskUiEvent()
}

class TaskViewModel : ViewModel() {

    private val repository = TaskRepository(RetrofitClient.apiService)

    private val _tasks = MutableStateFlow<List<Task>>(emptyList())
    val tasks: StateFlow<List<Task>> = _tasks

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage

    fun loadTasks(token: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            when (val result = repository.getTasks(token)) {
                is ApiResult.Success -> _tasks.value = result.data
                is ApiResult.Error -> _errorMessage.value = result.message
            }
            _isLoading.value = false
        }
    }

    fun createTask(token: String, title: String, description: String?) {
        viewModelScope.launch {
            _errorMessage.value = null
            when (val result = repository.createTask(token, title, description)) {
                is ApiResult.Success -> loadTasks(token)
                is ApiResult.Error -> _errorMessage.value = result.message
            }
        }
    }

    fun updateTask(token: String, task: Task) {
        viewModelScope.launch {
            _errorMessage.value = null
            when (val result = repository.updateTask(token, task)) {
                is ApiResult.Success -> loadTasks(token)
                is ApiResult.Error -> _errorMessage.value = result.message
            }
        }
    }

    fun toggleCompleted(token: String, task: Task) {
        updateTask(token, task.copy(completed = !task.completed))
    }

    fun deleteTask(token: String, id: Int) {
        viewModelScope.launch {
            _errorMessage.value = null
            when (val result = repository.deleteTask(token, id)) {
                is ApiResult.Success -> loadTasks(token)
                is ApiResult.Error -> _errorMessage.value = result.message
            }
        }
    }

    fun clearError() {
        _errorMessage.value = null
    }
}
