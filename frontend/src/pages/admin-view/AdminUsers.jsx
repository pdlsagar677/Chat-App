import { useEffect, useState } from "react";
import { useAuthStore } from "../../store/useAuthStore";
import { useNavigate, Link } from "react-router-dom";
import { axiosInstance } from "../../lib/axios";
import { toast, ToastContainer } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";

export const AdminUsers = () => {
  const { authUser } = useAuthStore();
  const navigate = useNavigate();
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!authUser) {
      navigate("/login");
    } else if (!authUser.isAdmin) {
      navigate("/");
    } else {
      getAllUsersData();
    }
  }, [authUser, navigate]);

  const getAllUsersData = async () => {
    try {
      const { data } = await axiosInstance.get("/admin/users");
      setUsers(data);
    } catch (err) {
      console.error("Failed to fetch users:", err);
    } finally {
      setLoading(false);
    }
  };

  const deleteUser = async (id) => {
    const isConfirmed = window.confirm("Are you sure you want to delete this user?");
    if (!isConfirmed) return;

    try {
      await axiosInstance.delete(`/admin/users/delete/${id}`);
      setUsers((prev) => prev.filter((user) => user._id !== id));
      toast.success("User deleted successfully!");
    } catch (err) {
      console.error("Error deleting user:", err);
    }
  };

  return (
    <div className="flex-1 flex flex-col overflow-auto">
      <ToastContainer position="top-right" autoClose={3000} />
      
      <div className="border-b p-4">
        <h1 className="text-xl font-semibold"> Users -Table</h1>
      </div>

      {loading ? (
        <div className="p-4 text-gray-500">Loading users...</div>
      ) : (
        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {users.map((user) => (
            <div
              key={user._id}
              className="flex items-center justify-between p-4 rounded-md border shadow-sm"
            >
              <div className="flex items-center gap-4">
                <img
                  src={user.profilePic || "/avatar.png"}
                  alt="profile"
                  className="w-10 h-10 rounded-full border"
                />
                <div>
                  <p className="font-medium">{user.username}</p>
                  <p className="text-sm text-gray-500">{user.email}</p>
                  <p className="text-sm text-gray-500">{user.phone}</p>
                </div>
              </div>
              <div className="flex gap-3">
                <Link
                  to={`/admin/users/${user._id}/edit`}
                  className="px-3 py-1 rounded-md bg-blue-500 text-white text-sm"
                >
                  Edit
                </Link>
                <button
                  onClick={() => deleteUser(user._id)}
                  className="px-3 py-1 rounded-md bg-red-500 text-white text-sm"
                >
                  Delete
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
