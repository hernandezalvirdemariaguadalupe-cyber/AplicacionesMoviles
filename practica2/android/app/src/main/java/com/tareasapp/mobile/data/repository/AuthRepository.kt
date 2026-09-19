package com.tareasapp.mobile.data.repository

import com.tareasapp.mobile.data.model.AuthRequest
import com.tareasapp.mobile.data.model.LoginResponse
import com.tareasapp.mobile.data.remote.ApiService
import com.tareasapp.mobile.data.remote.errorMessageOrDefault

sealed class ApiResult<out T> {
    data class Success<T>(val data: T) : ApiResult<T>()
    data class Error(val message: String) : ApiResult<Nothing>()
}

class AuthRepository(private val api: ApiService) {

    suspend fun register(username: String, password: String): ApiResult<String> {
        return try {
            val response = api.register(AuthRequest(username, password))
            if (response.isSuccessful) {
                ApiResult.Success(response.body()?.message ?: "Usuario registrado")
            } else {
                ApiResult.Error(response.errorMessageOrDefault("No se pudo registrar el usuario"))
            }
        } catch (e: Exception) {
            ApiResult.Error("Error de conexion: ${e.message}")
        }
    }

    suspend fun login(username: String, password: String): ApiResult<LoginResponse> {
        return try {
            val response = api.login(AuthRequest(username, password))
            if (response.isSuccessful && response.body() != null) {
                ApiResult.Success(response.body()!!)
            } else {
                ApiResult.Error(response.errorMessageOrDefault("Usuario o contrasena incorrectos"))
            }
        } catch (e: Exception) {
            ApiResult.Error("Error de conexion: ${e.message}")
        }
    }
}
