package com.tareasapp.mobile.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.tareasapp.mobile.data.local.SessionManager
import com.tareasapp.mobile.data.remote.RetrofitClient
import com.tareasapp.mobile.data.repository.ApiResult
import com.tareasapp.mobile.data.repository.AuthRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.launch

data class AuthUiState(
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val infoMessage: String? = null,
    val isLoggedIn: Boolean = false,
    val token: String? = null,
    val username: String? = null
)

class AuthViewModel(private val sessionManager: SessionManager) : ViewModel() {

    private val repository = AuthRepository(RetrofitClient.apiService)

    private val _uiState = MutableStateFlow(AuthUiState())
    val uiState: StateFlow<AuthUiState> = _uiState

    init {
        restoreSession()
    }

    private fun restoreSession() {
        viewModelScope.launch {
            val token = sessionManager.tokenFlow.firstOrNull()
            val username = sessionManager.usernameFlow.firstOrNull()
            if (!token.isNullOrBlank()) {
                _uiState.value = _uiState.value.copy(
                    isLoggedIn = true,
                    token = token,
                    username = username
                )
            }
        }
    }

    fun login(username: String, password: String) {
        if (username.isBlank() || password.isBlank()) {
            _uiState.value = _uiState.value.copy(errorMessage = "Ingresa usuario y contrasena")
            return
        }
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            when (val result = repository.login(username, password)) {
                is ApiResult.Success -> {
                    sessionManager.saveSession(result.data.access_token, result.data.user.username)
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        isLoggedIn = true,
                        token = result.data.access_token,
                        username = result.data.user.username
                    )
                }
                is ApiResult.Error -> {
                    _uiState.value = _uiState.value.copy(isLoading = false, errorMessage = result.message)
                }
            }
        }
    }

    fun register(username: String, password: String, confirmPassword: String) {
        if (username.isBlank() || password.isBlank()) {
            _uiState.value = _uiState.value.copy(errorMessage = "Ingresa usuario y contrasena")
            return
        }
        if (password != confirmPassword) {
            _uiState.value = _uiState.value.copy(errorMessage = "Las contrasenas no coinciden")
            return
        }
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            when (val result = repository.register(username, password)) {
                is ApiResult.Success -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        infoMessage = "Registro exitoso, ahora inicia sesion"
                    )
                }
                is ApiResult.Error -> {
                    _uiState.value = _uiState.value.copy(isLoading = false, errorMessage = result.message)
                }
            }
        }
    }

    fun logout() {
        viewModelScope.launch {
            sessionManager.clearSession()
            _uiState.value = AuthUiState()
        }
    }

    fun clearMessages() {
        _uiState.value = _uiState.value.copy(errorMessage = null, infoMessage = null)
    }
}
