package com.tareasapp.mobile

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.tareasapp.mobile.data.local.SessionManager
import com.tareasapp.mobile.ui.navigation.Screen
import com.tareasapp.mobile.ui.screens.LoginScreen
import com.tareasapp.mobile.ui.screens.RegisterScreen
import com.tareasapp.mobile.ui.screens.TasksScreen
import com.tareasapp.mobile.ui.theme.TareasAppTheme
import com.tareasapp.mobile.viewmodel.AuthViewModel
import com.tareasapp.mobile.viewmodel.AuthViewModelFactory
import com.tareasapp.mobile.viewmodel.TaskViewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            TareasAppTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    TareasAppRoot()
                }
            }
        }
    }
}

@Composable
fun TareasAppRoot() {
    val navController = rememberNavController()
    val context = LocalContext.current
    val sessionManager = remember { SessionManager(context.applicationContext) }
    val authViewModel: AuthViewModel = viewModel(factory = AuthViewModelFactory(sessionManager))
    val taskViewModel: TaskViewModel = viewModel()

    val authState by authViewModel.uiState.collectAsState()

    NavHost(navController = navController, startDestination = Screen.Login.route) {
        composable(Screen.Login.route) {
            LoginScreen(
                uiState = authState,
                onLogin = { username, password -> authViewModel.login(username, password) },
                onNavigateRegister = { navController.navigate(Screen.Register.route) },
                onNavigateTasks = { navController.navigate(Screen.Tasks.route) },
                onLogout = { authViewModel.logout() }
            )
            LaunchedEffect(authState.isLoggedIn) {
                if (authState.isLoggedIn) {
                    navController.navigate(Screen.Tasks.route) {
                        popUpTo(Screen.Login.route) { inclusive = true }
                    }
                }
            }
        }
        composable(Screen.Register.route) {
            RegisterScreen(
                uiState = authState,
                onRegister = { username, password, confirm ->
                    authViewModel.register(username, password, confirm)
                },
                onNavigateLogin = { navController.navigate(Screen.Login.route) },
                onNavigateTasks = { navController.navigate(Screen.Tasks.route) },
                onLogout = { authViewModel.logout() },
                onMessagesShown = { authViewModel.clearMessages() }
            )
        }
        composable(Screen.Tasks.route) {
            val token = authState.token
            if (token != null) {
                TasksScreen(
                    token = token,
                    taskViewModel = taskViewModel,
                    onNavigateLogin = { navController.navigate(Screen.Login.route) },
                    onLogout = {
                        authViewModel.logout()
                        navController.navigate(Screen.Login.route) {
                            popUpTo(0) { inclusive = true }
                        }
                    }
                )
            } else {
                LaunchedEffect(Unit) {
                    navController.navigate(Screen.Login.route) {
                        popUpTo(0) { inclusive = true }
                    }
                }
            }
        }
    }
}

