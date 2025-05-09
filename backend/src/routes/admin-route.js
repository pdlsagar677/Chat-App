// routes/admin-route.js
import express from "express";
import * as adminController from "../controllers/admin-controller.js";
import { protectRoute } from "../middleware/auth-middleware.js"; // Using protectRoute
import adminMiddleware from "../middleware/admin-middleware.js"; // If you still want to use this

const router = express.Router();

// User routes with both protectRoute and adminMiddleware
router.route("/users").get(protectRoute, adminMiddleware, adminController.getAllUsers);
router.route("/users/:id").get(protectRoute, adminMiddleware, adminController.getUserById);
router.route("/users/delete/:id").delete(protectRoute, adminMiddleware, adminController.deleteUserById);
router.route("/users/update/:id").patch(protectRoute, adminMiddleware, adminController.updateUserById);

export default router; // Default export
