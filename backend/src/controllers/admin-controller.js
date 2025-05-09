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

// Delete a user by ID
export const deleteUserById = async (req, res, next) => {
  try {
    const id = req.params.id;
    const deleted = await User.deleteOne({ _id: id });
    if (deleted.deletedCount === 0) {
      return res.status(404).json({ message: "User not found or already deleted" });
    }
    return res.status(200).json({ message: "User deleted successfully" });
  } catch (error) {
    console.error("Error deleting user:", error);
    next(error); // Pass error to the error handling middleware
  }
};

// Update a user by ID
export const updateUserById = async (req, res, next) => {
  try {
    const id = req.params.id;
    const updatedUserData = req.body;

    const result = await User.updateOne(
      { _id: id },
      { $set: updatedUserData }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ message: "User not found" });
    }

    return res.status(200).json({ message: "User updated successfully" });
  } catch (error) {
    console.error("Error updating user:", error);
    next(error); // Pass error to the error handling middleware
  }
};
