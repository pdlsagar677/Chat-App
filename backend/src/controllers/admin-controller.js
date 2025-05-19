import User from "../models/user-model.js"; // Import User model

// Get all users (excluding passwords)
export const getAllUsers = async (req, res, next) => {
  try {
    const users = await User.find({}, { password: 0 }); // Exclude password
    if (!users || users.length === 0) {
      return res.status(404).json({ message: "No users found" });
    }
    return res.status(200).json(users);
  } catch (error) {
    console.error("Error fetching users:", error);
    next(error); // Pass error to the error handling middleware
  }
};

// Get a single user by ID (excluding password)
export const getUserById = async (req, res, next) => {
  try {
    const id = req.params.id;
    const user = await User.findById(id, { password: 0 }); // cleaner with findById
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }
    return res.status(200).json(user);
  } catch (error) {
    console.error("Error fetching user by ID:", error);
    next(error); // Pass error to the error handling middleware
  }
};

