package com.tareasapp.mobile.ui.components

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue

/**
 * Menu de navegacion desplegable que permite ir a Inicio de Sesion, Registro
 * o a las operaciones CRUD (Mis tareas), tal como pide la practica.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppTopBar(
    title: String,
    isLoggedIn: Boolean,
    onNavigateLogin: () -> Unit,
    onNavigateRegister: () -> Unit,
    onNavigateTasks: () -> Unit,
    onLogout: () -> Unit
) {
    var expanded by remember { mutableStateOf(false) }

    TopAppBar(
        title = { Text(title) },
        actions = {
            IconButton(onClick = { expanded = true }) {
                Icon(Icons.Filled.MoreVert, contentDescription = "Menu de navegacion")
            }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                if (!isLoggedIn) {
                    DropdownMenuItem(
                        text = { Text("Inicio de sesion") },
                        onClick = { expanded = false; onNavigateLogin() }
                    )
                    DropdownMenuItem(
                        text = { Text("Registro de usuario") },
                        onClick = { expanded = false; onNavigateRegister() }
                    )
                } else {
                    DropdownMenuItem(
                        text = { Text("Mis tareas (CRUD)") },
                        onClick = { expanded = false; onNavigateTasks() }
                    )
                    DropdownMenuItem(
                        text = { Text("Cerrar sesion") },
                        onClick = { expanded = false; onLogout() }
                    )
                }
            }
        }
    )
}
