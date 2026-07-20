/**
 * Reemplaza estos enlaces cuando tengas las tiendas / la web app publicadas.
 */
const STORE_URLS = {
  android: "#android", // https://play.google.com/store/apps/details?id=...
  ios: "#ios", // https://apps.apple.com/app/id...
  web: "#web", // https://app.tudominio.com
};

function detectPreferredStore() {
  const ua = navigator.userAgent || "";
  if (/android/i.test(ua)) return "android";
  if (/iPad|iPhone|iPod/.test(ua) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1)) {
    return "ios";
  }
  return "web";
}

function wireStoreLinks() {
  const preferred = detectPreferredStore();

  document.querySelectorAll("[data-store]").forEach((anchor) => {
    const key = anchor.getAttribute("data-store");
    const url = STORE_URLS[key];
    if (url) anchor.setAttribute("href", url);
    if (key === preferred) anchor.classList.add("is-preferred");
  });
}

wireStoreLinks();
