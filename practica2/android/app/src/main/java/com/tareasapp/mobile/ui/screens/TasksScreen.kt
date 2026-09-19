package com.tareasapp.mobile.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.Card
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import com.tareasapp.mobile.data.model.Task
import com.tareasapp.mobile.ui.components.AppTopBar
import com.tareasapp.mobile.viewmodel.TaskViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TasksScreen(
    token: String,
    taskViewModel: TaskViewModel,
    onNavigateLogin: () -> Unit,
    onLogout: () -> Unit
) {
    val tasks by taskViewModel.tasks.collectAsState()
    val isLoading by taskViewModel.isLoading.collectAsState()
    val errorMessage by taskViewModel.errorMessage.collectAsState()

    var showDialog by remember { mutableStateOf(false) }
    var taskToEdit by remember { mutableStateOf<Task?>(null) }

    LaunchedEffect(Unit) {
        taskViewModel.loadTasks(token)
    }

    Scaffold(
        topBar = {
            AppTopBar(
                title = "Mis tareas",
                isLoggedIn = true,
                onNavigateLogin = onNavigateLogin,
                onNavigateRegister = {},
                onNavigateTasks = {},
                onLogout = onLogout
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = { taskToEdit = null; showDialog = true }) {
                Icon(Icons.Filled.Add, contentDescription = "Agregar tarea")
            }
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when {
                isLoading && tasks.isEmpty() -> {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                }
                tasks.isEmpty() -> {
                    Text(
                        text = "Aun no tienes tareas. Toca + para crear la primera.",
                        modifier = Modifier
                            .align(Alignment.Center)
                            .padding(24.dp)
                    )
                }
                else -> {
                    LazyColumn(modifier = Modifier.fillMaxSize().padding(12.dp)) {
                        items(tasks, key = { it.id }) { task ->
                            TaskItem(
                                task = task,
                                onToggle = { taskViewModel.toggleCompleted(token, task) },
                                onEdit = { taskToEdit = task; showDialog = true },
                                onDelete = { taskViewModel.deleteTask(token, task.id) }
                            )
                        }
                    }
                }
            }

            errorMessage?.let {
                Text(
                    text = it,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(16.dp)
                )
            }
        }
    }

    if (showDialog) {
        TaskFormDialog(
            taskToEdit = taskToEdit,
            onDismiss = { showDialog = false },
            onConfirm = { title, description ->
                val current = taskToEdit
                if (current == null) {
                    taskViewModel.createTask(token, title, description.ifBlank { null })
                } else {
                    taskViewModel.updateTask(token, current.copy(title = title, description = description.ifBlank { null }))
                }
                showDialog = false
            }
        )
    }
}

@Composable
private fun TaskItem(
    task: Task,
    onToggle: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    Card(modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                Checkbox(checked = task.completed, onCheckedChange = { onToggle() })
                Column {
                    Text(
                        text = task.title,
                        style = MaterialTheme.typography.titleMedium,
                        textDecoration = if (task.completed) TextDecoration.LineThrough else null
                    )
                    task.description?.takeIf { it.isNotBlank() }?.let {
                        Text(text = it, style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
            IconButton(onClick = onEdit) {
                Icon(Icons.Filled.Edit, contentDescription = "Editar tarea")
            }
            IconButton(onClick = onDelete) {
                Icon(Icons.Filled.Delete, contentDescription = "Eliminar tarea")
            }
        }
    }
}
