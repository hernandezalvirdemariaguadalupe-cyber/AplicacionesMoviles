package com.tareasapp.mobile.data.remote

import com.tareasapp.mobile.data.model.AuthRequest
import com.tareasapp.mobile.data.model.LoginResponse
import com.tareasapp.mobile.data.model.MessageResponse
import com.tareasapp.mobile.data.model.Task
import com.tareasapp.mobile.data.model.TaskRequest
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.POST
import retrofit2.http.PUT
import retrofit2.http.Path

interface ApiService {

    @POST("register")
    suspend fun register(@Body request: AuthRequest): Response<MessageResponse>

    @POST("login")
    suspend fun login(@Body request: AuthRequest): Response<LoginResponse>

    @GET("tasks")
    suspend fun getTasks(@Header("Authorization") token: String): Response<List<Task>>

    @POST("tasks")
    suspend fun createTask(
        @Header("Authorization") token: String,
        @Body request: TaskRequest
    ): Response<Task>

    @PUT("tasks/{id}")
    suspend fun updateTask(
        @Header("Authorization") token: String,
        @Path("id") id: Int,
        @Body request: TaskRequest
    ): Response<Task>

    @DELETE("tasks/{id}")
    suspend fun deleteTask(
        @Header("Authorization") token: String,
        @Path("id") id: Int
    ): Response<MessageResponse>
}
