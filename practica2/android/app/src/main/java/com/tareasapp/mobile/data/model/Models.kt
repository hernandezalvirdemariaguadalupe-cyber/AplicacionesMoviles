package com.tareasapp.mobile.data.model

data class AuthRequest(
    val username: String,
    val password: String
)

data class UserDto(
    val id: Int,
    val username: String,
    val created_at: String
)

data class LoginResponse(
    val access_token: String,
    val user: UserDto
)

data class MessageResponse(
    val message: String? = null,
    val error: String? = null
)

data class Task(
    val id: Int = 0,
    val title: String,
    val description: String? = null,
    val completed: Boolean = false,
    val created_at: String? = null,
    val updated_at: String? = null,
    val user_id: Int? = null
)

data class TaskRequest(
    val title: String,
    val description: String? = null,
    val completed: Boolean = false
)
