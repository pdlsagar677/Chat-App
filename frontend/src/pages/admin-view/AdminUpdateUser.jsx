import { useEffect, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { useAuthStore } from "../../store/useAuthStore";
import toast from "react-hot-toast";
import { axiosInstance } from "../../lib/axios";

const AdminEditUser = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const { authUser } = useAuthStore();

  const [form, setForm] = useState({ fullName: "", email: "" });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchUser = async () => {
      try {
        const { data } = await axiosInstance.get(`/admin/users/${id}`);
        setForm({
          fullName: data.fullName || "",
          email: data.email || "",
        });
      } catch (err) {
        console.error("Failed to fetch user", err);
        toast.error("User not found.");
        navigate("/admin/users");
      } finally {
        setLoading(false);
      }
    };

    if (authUser && id) {
      fetchUser();
    }
  }, [id, authUser, navigate]);

  const handleChange = (e) => {
    const { name, value } = e.target;
    setForm((prev) => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    try {
      await axiosInstance.patch(`/admin/users/update/${id}`, form);
      toast.success("User updated successfully");
      navigate("/admin/users");
    } catch (error) {
      toast.error("Failed to update user");
      console.error(error);
    }
  };

  if (loading) return <div className="p-4">Loading user...</div>;

  return (
    <div className="p-4 h-full w-full flex justify-center items-center">
      <div className="chat-container max-w-md w-full bg-base-200 p-6 rounded-2xl shadow-md space-y-6">
        <h2 className="text-xl font-bold text-center">Edit User</h2>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">Full Name</label>
            <input
              type="text"
              name="fullName"
              value={form.fullName}
              onChange={handleChange}
              className="w-full p-2 rounded border border-zinc-600 bg-base-100"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Email</label>
            <input
              type="email"
              name="email"
              value={form.email}
              onChange={handleChange}
              className="w-full p-2 rounded border border-zinc-600 bg-base-100"
              required
            />
          </div>

          <button
            type="submit"
            className="px-3 py-1.5 bg-teal-500 text-white rounded-full hover:bg-teal-600 transition duration-200 shadow-md"
            >
            Save Changes
          </button>
        </form>
      </div>
    </div>
  );
};

export default AdminEditUser;
