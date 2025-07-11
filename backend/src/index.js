import express from "express";
import authRoutes from "./routes/auth-route.js";
import dotenv from "dotenv";
import cors from "cors";
import { connectDB } from "./lib/db.js";
import cookieParser from "cookie-parser";
import messageRoutes from "./routes/message-route.js";
import adminRoutes from "./routes/admin-route.js"
import videoCallRoute from "./routes/videocall-route.js"
import bodyParser from 'body-parser';
import {app,server } from "./lib/socket.js";
import path from "path";



// Load environment variables
dotenv.config();
const PORT = process.env.PORT;
const __dirname = path.resolve();

// Increase the size limit to handle large file uploads
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ limit: '50mb', extended: true }));

// Middlewares
app.use(express.json());
app.use(cookieParser());

// CORS configuration
app.use(cors({
  origin: ["http://localhost:5173","http://localhost:5172",
  
      
  ], 
  credentials: true  // Required for cookies/session
}));

// Use the auth routes for the /api/auth endpoint
app.use("/api/auth", authRoutes);
app.use("/api/messages", messageRoutes);
app.use("/api/admin", adminRoutes);
app.use('/api', videoCallRoute);



if (process.env.NODE_ENV === "production") {
    app.use(express.static(path.join(__dirname, "../frontend/dist")));
  
    app.get("*", (req, res) => {
      res.sendFile(path.join(__dirname, "../frontend", "dist", "index.html"));
    });
  }
  
// Start the server and connect to the database
server.listen(PORT,'0.0.0.0', async () => {
    console.log("Server is running on port " + PORT);
    try {
        await connectDB(); // Assuming connectDB is an async function
        console.log("Database connected successfully");
    } catch (err) {
        console.error("Database connection failed", err);
    }
});