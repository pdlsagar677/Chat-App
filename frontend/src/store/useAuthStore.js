import { create } from "zustand";
import { axiosInstance } from "../lib/axios.js";
import toast from "react-hot-toast";
import { io } from "socket.io-client";

// const BASE_URL = import.meta.env.MODE === "development" ? "http://localhost:5001" : "/";
const BASE_URL = import.meta.env.MODE === "development" ? "http://192.168.1.102:5001" : "/";

export const useAuthStore = create((set, get) => ({
  authUser: null,
  isSigningUp: false,
  isLoggingIn: false,
  isUpdatingProfile: false,
  isCheckingAuth: true,
  onlineUsers: [],
  socket: null,

  checkAuth: async () => {
    try {
      const res = await axiosInstance.get("/auth/check");

      set({ authUser: res.data });
      get().connectSocket();
    } catch (error) {
      console.log("Error in checkAuth:", error);
      set({ authUser: null });
    } finally {
      set({ isCheckingAuth: false });
    }
  },

  signup: async (data) => {
    set({ isSigningUp: true });
    try {
      const res = await axiosInstance.post("/auth/signup", data);
      set({ authUser: res.data });
      toast.success("Account created successfully");
      get().connectSocket();
    } catch (error) {
      toast.error(error.response.data.message);
    } finally {
      set({ isSigningUp: false });
    }
  },

  login: async (data) => {
    set({ isLoggingIn: true });
    try {
      const res = await axiosInstance.post("/auth/login", data);
      set({ authUser: res.data });
      toast.success("Logged in successfully");

      get().connectSocket();
    } catch (error) {
      toast.error(error.response.data.message);
    } finally {
      set({ isLoggingIn: false });
    }
  },

  logout: async () => {
    try {
      await axiosInstance.post("/auth/logout");
      set({ authUser: null });
      toast.success("Logged out successfully");
      get().disconnectSocket();
    } catch (error) {
      toast.error(error.response.data.message);
    }
  },

  updateProfile: async (data) => {
    set({ isUpdatingProfile: true });
    try {
      const res = await axiosInstance.put("/auth/update-profile", data);
      set({ authUser: res.data });
      toast.success("Profile updated successfully");
    } catch (error) {
      console.log("error in update profile:", error);
      toast.error(error.response.data.message);
    } finally {
      set({ isUpdatingProfile: false });
    }
  },

  connectSocket: () => {
    const { authUser } = get();
    if (!authUser || get().socket?.connected) return;
  
    const socket = io(BASE_URL, {
      query: {
        userId: authUser._id,
      },
    });
  
    socket.connect();
    set({ socket });
  
    socket.on("getOnlineUsers", (userIds) => {
      set({ onlineUsers: userIds });
    });
  
    // Video call signaling events (existing)
    socket.on("incomingCall", (data) => {
      console.log("Incoming video call from:", data);
      // TODO: UI update or notification for incoming video call
    });
  
    socket.on("callAccepted", (data) => {
      console.log("Video call accepted by:", data);
    });
  
    socket.on("callEnded", () => {
      console.log("Video call ended");
    });
  
    // --- Add audio call signaling events here ---
  
    socket.on("audio-incomingCall", (data) => {
      console.log("Incoming audio call from:", data);
      // TODO: Trigger audio call UI update or notification
    });
  
    socket.on("audio-callAccepted", (data) => {
      console.log("Audio call accepted by:", data);
    });
  
    socket.on("audio-callEnded", () => {
      console.log("Audio call ended");
    });
  
    // Add audio WebRTC signaling messages:
    socket.on("audio-offer", (payload) => {
      console.log("Received audio offer:", payload);
      // Handle offer in your audio call component
    });
  
    socket.on("audio-answer", (payload) => {
      console.log("Received audio answer:", payload);
      // Handle answer in your audio call component
    });
  
    socket.on("audio-ice-candidate", (payload) => {
      console.log("Received audio ice candidate:", payload);
      // Handle ICE candidate in your audio call component
    });
  },
  
  
  disconnectSocket: () => {
    if (get().socket?.connected) get().socket.disconnect();
  },
}));