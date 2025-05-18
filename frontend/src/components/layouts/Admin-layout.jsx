import { useState, useEffect } from "react";
import { NavLink, Outlet, Navigate, useLocation } from "react-router-dom";
import { Home, Users, Image as BannerIcon } from "lucide-react";
import { useAuthStore } from "../../store/useAuthStore";

const AdminLayout = () => {
  const { authUser, isCheckingAuth } = useAuthStore();
  const location = useLocation();
  const [selectedTab, setSelectedTab] = useState("home");

  const tabs = [
    { key: "home", label: "Home", icon: <Home className="size-5" />, path: "/admin/home" },
    { key: "users", label: "Users", icon: <Users className="size-5" />, path: "/admin/users" },
    { key: "banner", label: "Banner", icon: <BannerIcon className="size-5" />, path: "/admin/banner" },
  ];

  useEffect(() => {
    const currentTab = tabs.find((tab) => location.pathname.startsWith(tab.path));
    if (currentTab) {
      setSelectedTab(currentTab.key);
    }
  }, [location.pathname]);

  if (isCheckingAuth) return <div>Loading...</div>;

  if (!authUser?.isAdmin) return <Navigate to="/" />;

  return (
    <div className="flex h-screen">
      <aside className="h-full w-20 lg:w-72 border-r border-base-300 flex flex-col transition-all duration-200">
        <div className="border-b border-base-300 w-full p-5">
          <div className="flex items-center gap-2">
            <Users className="size-6" />
            <span className="font-medium hidden lg:block">Admin Panel</span>
          </div>
        </div>

        <div className="overflow-y-auto w-full py-3 flex flex-col gap-1">
          {tabs.map((tab) => (
            <NavLink
              key={tab.key}
              to={tab.path}
              onClick={() => setSelectedTab(tab.key)}
              className={({ isActive }) => `
                w-full p-3 flex items-center gap-3
                hover:bg-base-300 transition-colors
                ${isActive ? "bg-base-300 ring-1 ring-base-300" : ""}
              `}
            >
              <div className="mx-auto lg:mx-0">{tab.icon}</div>
              <span className="hidden lg:block text-left font-medium">{tab.label}</span>
            </NavLink>
          ))}
        </div>
      </aside>

      <main className="flex-1 overflow-auto">
        <Outlet />
      </main>
    </div>
  );
};

export default AdminLayout;
