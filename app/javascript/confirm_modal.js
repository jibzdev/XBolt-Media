function resetConfirmModal() {
  const modal = document.getElementById("confirm-modal");
  const backdrop = document.getElementById("confirm-backdrop");
  const dialog = document.getElementById("confirm-dialog");

  if (!modal) return;

  modal.classList.add("hidden", "pointer-events-none");
  modal.classList.remove("pointer-events-auto");
  modal.setAttribute("aria-hidden", "true");
  backdrop?.classList.add("opacity-0", "pointer-events-none");
  backdrop?.classList.remove("opacity-100", "pointer-events-auto");
  dialog?.classList.add("scale-95", "opacity-0");
  dialog?.classList.remove("scale-100", "opacity-100");
}

function showConfirmModal(message) {
  return new Promise((resolve) => {
    const modal = document.getElementById("confirm-modal");
    const backdrop = document.getElementById("confirm-backdrop");
    const dialog = document.getElementById("confirm-dialog");
    const messageEl = document.getElementById("confirm-message");
    const cancelBtn = document.getElementById("confirm-cancel");
    const acceptBtn = document.getElementById("confirm-accept");

    if (!modal) { resolve(confirm(message)); return; }

    messageEl.textContent = message;
    modal.classList.remove("hidden", "pointer-events-none");
    modal.classList.add("pointer-events-auto");
    modal.setAttribute("aria-hidden", "false");

    requestAnimationFrame(() => {
      backdrop.classList.remove("opacity-0", "pointer-events-none");
      backdrop.classList.add("opacity-100", "pointer-events-auto");
      dialog.classList.remove("scale-95", "opacity-0");
      dialog.classList.add("scale-100", "opacity-100");
    });

    function close(result) {
      backdrop.classList.remove("opacity-100", "pointer-events-auto");
      backdrop.classList.add("opacity-0", "pointer-events-none");
      dialog.classList.remove("scale-100", "opacity-100");
      dialog.classList.add("scale-95", "opacity-0");
      modal.classList.remove("pointer-events-auto");
      modal.classList.add("pointer-events-none");
      modal.setAttribute("aria-hidden", "true");

      setTimeout(() => { modal.classList.add("hidden"); }, 200);

      cancelBtn.removeEventListener("click", onCancel);
      acceptBtn.removeEventListener("click", onAccept);
      backdrop.removeEventListener("click", onCancel);
      document.removeEventListener("keydown", onKey);
      resolve(result);
    }

    function onCancel() { close(false); }
    function onAccept() { close(true); }
    function onKey(e) { if (e.key === "Escape") close(false); }

    cancelBtn.addEventListener("click", onCancel);
    acceptBtn.addEventListener("click", onAccept);
    backdrop.addEventListener("click", onCancel);
    document.addEventListener("keydown", onKey);

    acceptBtn.focus();
  });
}

document.addEventListener("DOMContentLoaded", resetConfirmModal);
document.addEventListener("turbo:load", resetConfirmModal);
document.addEventListener("turbo:before-cache", resetConfirmModal);

const T = window.Turbo;
if (T && typeof T.setConfirmMethod === "function") {
  T.setConfirmMethod(showConfirmModal);
} else if (T && T.config && T.config.forms) {
  T.config.forms.confirm = showConfirmModal;
}
