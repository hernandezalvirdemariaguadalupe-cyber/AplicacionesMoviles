package com.tareasapp.mobile.data.remote

import com.google.gson.Gson
import com.tareasapp.mobile.data.model.MessageResponse
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Response
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit

object RetrofitClient {

    /**
     * En emulador se usaria 10.0.2.2 (alias del localhost del equipo anfitrion).
     * Como aqui se prueba en un dispositivo fisico, se usa la IP local del
     * equipo en la red Wi-Fi (celular y PC deben estar en la misma red).
     */
    private const val BASE_URL = "http://10.100.71.49:5000/"

    private val loggingInterceptor = HttpLoggingInterceptor().apply {
        level = HttpLoggingInterceptor.Level.BODY
    }

    private val okHttpClient = OkHttpClient.Builder()
        .addInterceptor(loggingInterceptor)
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    val apiService: ApiService by lazy {
        Retrofit.Builder()
            .baseUrl(BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(ApiService::class.java)
    }
}

/** Extrae el mensaje de error del cuerpo JSON de una respuesta fallida de la API. */
fun <T> Response<T>.errorMessageOrDefault(default: String): String {
    return try {
        val errorBody = errorBody()?.string()
        if (errorBody.isNullOrBlank()) {
            default
        } else {
            Gson().fromJson(errorBody, MessageResponse::class.java).error ?: default
        }
    } catch (e: Exception) {
        default
    }
}
