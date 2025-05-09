import React, { useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'; // Import BrowserRouter and Navigate
import Navbar from './components/Navbar';
import HomePage from './pages/HomePage';
import LoginPage from './pages/LoginPage';
import SignUpPage from './pages/SignUpPage';
import SettingsPage from './pages/SettingsPage';
import ProfilePage from './pages/ProfilePage';
import { useAuthStore } from './store/useAuthStore';
import { Loader } from "lucide-react";
import { Toaster } from "react-hot-toast";
import { useThemeStore } from './store/useThemeStore';


const App = () => {
  // Destructure both authUser and isCheckingAuth from the useAuthStore
  const { authUser, checkAuth, isCheckingAuth ,onlineUsers } = useAuthStore();
  const { theme } = useThemeStore();


 console.log(onlineUsers);
  // Use useEffect to trigger the checkAuth function once on component mount
  useEffect(() => {
    checkAuth();
  }, [checkAuth]);

  // Show the loading spinner if checking auth and no user is authenticated
  if (isCheckingAuth && !authUser) {
    return (
      <div className="flex items-center justify-center h-screen">
        <Loader className="size-10 animate-spin" />
      </div>
    );
  }

  return (
    <Router>
      <div  data-theme={theme}>
        <Navbar />
        <Routes>
          <Route path="/" element={authUser ? <HomePage /> : <Navigate to="/login" />} />
          <Route path="/signup" element={!authUser ? <SignUpPage /> : <Navigate to="/" />} />
          <Route path="/login" element={!authUser ? <LoginPage /> : <Navigate to="/" />} />
          <Route path="/settings" element={<SettingsPage />} />
          <Route path="/profile" element={authUser ? <ProfilePage /> : <Navigate to="/login" />} />
        </Routes>


        <Toaster />
      </div>
    </Router>
  );
};

export default App;
