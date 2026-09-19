package com.tareasapp.mobile.data.repository

import com.tareasapp.mobile.data.model.Task
import com.tareasapp.mobile.data.model.TaskRequest
import com.tareasapp.mobile.data.remote.ApiService
import com.tareasapp.mobile.data.remote.errorMessageOrDefault

class TaskRepository(private val api: ApiService) {

    suspend fun getTasks(token: String): ApiResult<List<Task>> {
        return try {
            val response = api.getTasks("Bearer $token")
            if (response.isSuccessful && response.body() != null) {
                ApiResult.Success(response.body()!!)
            } else {
                ApiResult.Error(response.errorMessageOrDefault("No se pudieron obtener las tareas"))
            }
        } catch (e: Exception) {
            ApiResult.Error("Error de conexion: ${e.message}")
        }
    }

    suspend fun createTask(token: String, title: String, description: String?): ApiResult<Task> {
        return try {
            val response = api.createTask("Bearer $token", TaskRequest(title, description))
            if (response.isSuccessful && response.body() != null) {
                ApiResult.Success(response.body()!!)
            } else {
                ApiResult.Error(response.errorMessageOrDefault("No se pudo crear la tarea"))
            }
        } catch (e: Exception) {
            ApiResult.Error("Error de conexion: ${e.message}")
        }
    }

    suspend fun updateTask(token: String, task: Task): ApiResult<Task> {
        return try {
            val response = api.updateTask(
                "Bearer $token",
                task.id,
                TaskRequest(task.title, task.description, task.completed)
            )
            if (response.isSuccessful && response.body() != null) {
                ApiResult.Success(response.body()!!)
            } else {
                ApiResult.Error(response.errorMessageOrDefault("No se pudo actualizar la tarea"))
            }
        } catch (e: Exception) {
            ApiResult.Error("Error de conexion: ${e.message}")
        }
    }

    suspend fun deleteTask(token: String, id: Int): ApiResult<Unit> {
        return try {
            val response = api.deleteTask("Bearer $token", id)
            if (response.isSuccessful) {
                ApiResult.Success(Unit)
            } else {
                ApiResult.Error(response.errorMessageOrDefault("No se pudo eliminar la tarea"))
            }
        } catch (e: Exception) {
            ApiResult.Error("Error de conexion: ${e.message}")
        }
    }
}
