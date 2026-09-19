package com.tareasapp.mobile.data.local

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.dataStore by preferencesDataStore(name = "sesion")

/**
 * Guarda el token JWT y el nombre de usuario en el almacenamiento local del
 * dispositivo para que la sesion persista entre reinicios de la app.
 */
class SessionManager(private val context: Context) {

    private val tokenKey = stringPreferencesKey("access_token")
    private val usernameKey = stringPreferencesKey("username")

    val tokenFlow: Flow<String?> = context.dataStore.data.map { it[tokenKey] }
    val usernameFlow: Flow<String?> = context.dataStore.data.map { it[usernameKey] }

    suspend fun saveSession(token: String, username: String) {
        context.dataStore.edit {
            it[tokenKey] = token
            it[usernameKey] = username
        }
    }

    suspend fun clearSession() {
        context.dataStore.edit { it.clear() }
    }
}
