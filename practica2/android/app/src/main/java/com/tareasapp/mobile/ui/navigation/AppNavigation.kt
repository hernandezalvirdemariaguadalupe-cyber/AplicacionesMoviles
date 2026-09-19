package com.tareasapp.mobile.ui.navigation

sealed class Screen(val route: String) {
    object Login : Screen("login")
    object Register : Screen("register")
    object Tasks : Screen("tasks")
}
