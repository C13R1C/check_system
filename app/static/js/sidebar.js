document.addEventListener("DOMContentLoaded", () => {
  const sidebar = document.getElementById("sidebar");
  const overlay = document.getElementById("sidebarOverlay");
  const btnCollapse = document.getElementById("btnCollapse");
  const btnToggleSidebar = document.getElementById("btnToggleSidebar");
  const mobileBreakpoint = 768;

  if (!sidebar || !overlay) return;

  function isMobile() {
    return window.innerWidth <= mobileBreakpoint;
  }

  function isSidebarOpen() {
    if (isMobile()) return sidebar.classList.contains("mobile-open");
    return !sidebar.classList.contains("collapsed");
  }

  function notifySidebarState() {
    window.dispatchEvent(new CustomEvent("coyolabs:sidebar-state", {
      detail: { open: isSidebarOpen(), mobile: isMobile() },
    }));
  }

  function closeMobileSidebar() {
    sidebar.classList.remove("mobile-open");
    overlay.classList.remove("show");
    document.body.style.overflow = "";
    notifySidebarState();
  }

  function openMobileSidebar() {
    sidebar.classList.add("mobile-open");
    overlay.classList.add("show");
    document.body.style.overflow = "hidden";
    notifySidebarState();
  }

  function toggleCollapseDesktop() {
    if (isMobile()) return;
    sidebar.classList.toggle("collapsed");
    notifySidebarState();
  }

  function toggleSidebarFromLogo() {
    if (isMobile()) {
      if (sidebar.classList.contains("mobile-open")) closeMobileSidebar();
      else openMobileSidebar();
      return isSidebarOpen();
    }
    sidebar.classList.toggle("collapsed");
    notifySidebarState();
    return isSidebarOpen();
  }

  function resetDesktopStateOnMobile() {
    if (isMobile()) {
      sidebar.classList.remove("collapsed");
    } else {
      sidebar.classList.add("collapsed");
      sidebar.classList.remove("mobile-open");
      overlay.classList.remove("show");
      document.body.style.overflow = "";
    }
    notifySidebarState();
  }

  window.coyolabsSidebar = {
    toggleFromLogo: toggleSidebarFromLogo,
    close: closeMobileSidebar,
    isOpen: isSidebarOpen,
  };

  if (btnCollapse) {
    btnCollapse.addEventListener("click", toggleCollapseDesktop);
  }

  if (btnToggleSidebar) {
    btnToggleSidebar.addEventListener("click", () => {
      if (sidebar.classList.contains("mobile-open")) {
        closeMobileSidebar();
      } else {
        openMobileSidebar();
      }
    });
  }

  overlay.addEventListener("click", closeMobileSidebar);

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      closeMobileSidebar();
    }
  });

  sidebar.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => {
      if (isMobile()) {
        closeMobileSidebar();
      }
    });
  });

  window.addEventListener("resize", resetDesktopStateOnMobile);

  resetDesktopStateOnMobile();
});
