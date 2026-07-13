const INSTAGRAM_JSON_PATH = "./instagram-latest.json";
const INSTAGRAM_FALLBACK_URL = "https://www.instagram.com/p/DVM3FVxErTp/";

const menuButton = document.querySelector(".menu-button");
const siteNav = document.querySelector(".site-nav");
const revealItems = document.querySelectorAll(".reveal");
const instagramSlots = document.querySelectorAll(".instagram-live-slot");
const footerMessagesLink = document.getElementById("footer-messages-link");
const workEntries = Array.from(document.querySelectorAll(".work-entry"));
const workPreview = document.getElementById("work-preview");
const workDialog = document.getElementById("work-dialog");

const messagePages = [
  "./words-help-ever.html",
  "./words-interpretations.html",
  "./words-existence.html",
];

if (footerMessagesLink) {
  footerMessagesLink.addEventListener("click", (event) => {
    event.preventDefault();
    const randomIndex = Math.floor(Math.random() * messagePages.length);
    window.location.href = messagePages[randomIndex];
  });
}

if (menuButton && siteNav) {
  menuButton.addEventListener("click", () => {
    const isOpen = siteNav.classList.toggle("is-open");
    menuButton.setAttribute("aria-expanded", String(isOpen));
  });

  siteNav.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => {
      siteNav.classList.remove("is-open");
      menuButton.setAttribute("aria-expanded", "false");
    });
  });
}

if (workEntries.length && workPreview && workDialog) {
  const previewImage = workPreview.querySelector(".work-preview-visual img");
  const previewVisual = workPreview.querySelector(".work-preview-visual");
  const previewMeta = workPreview.querySelector("[data-work-meta]");
  const previewTitle = workPreview.querySelector("[data-work-title]");
  const previewDescription = workPreview.querySelector("[data-work-description]");
  const previewTags = workPreview.querySelector("[data-work-tags]");
  const previewLink = workPreview.querySelector(".work-preview-link");
  const dialogImage = workDialog.querySelector(".work-dialog-image");
  const dialogMeta = workDialog.querySelector("[data-dialog-meta]");
  const dialogTitle = workDialog.querySelector("[data-dialog-title]");
  const dialogDescription = workDialog.querySelector("[data-dialog-description]");
  const dialogTags = workDialog.querySelector("[data-dialog-tags]");
  const dialogLink = workDialog.querySelector("[data-dialog-link]");
  let previewTimer;

  const getWorkData = (entry) => ({
    url: entry.dataset.url,
    title: entry.dataset.title,
    meta: entry.dataset.meta,
    description: entry.dataset.description,
    image: entry.dataset.image,
    tags: (entry.dataset.tags || "").split(",").filter(Boolean),
  });

  const renderTags = (container, tags) => {
    container.replaceChildren(...tags.map((tag) => {
      const chip = document.createElement("span");
      chip.textContent = tag;
      return chip;
    }));
  };

  const updatePreview = (entry) => {
    if (entry.classList.contains("is-active")) return;
    workEntries.forEach((item) => {
      const isActive = item === entry;
      item.classList.toggle("is-active", isActive);
      item.querySelector(".work-index-button").setAttribute("aria-pressed", String(isActive));
    });

    clearTimeout(previewTimer);
    workPreview.classList.add("is-changing");
    previewTimer = window.setTimeout(() => {
      const data = getWorkData(entry);
      previewImage.src = data.image;
      previewImage.alt = `${data.title} のOGP画像`;
      previewVisual.href = data.url;
      previewMeta.textContent = data.meta;
      previewTitle.textContent = data.title;
      previewDescription.textContent = data.description;
      previewLink.href = data.url;
      renderTags(previewTags, data.tags);
      workPreview.classList.remove("is-changing");
    }, 110);
  };

  const openWorkDialog = (entry) => {
    const data = getWorkData(entry);
    dialogImage.src = data.image;
    dialogImage.alt = `${data.title} のOGP画像`;
    dialogMeta.textContent = data.meta;
    dialogTitle.textContent = data.title;
    dialogDescription.textContent = data.description;
    dialogLink.href = data.url;
    renderTags(dialogTags, data.tags);

    if (typeof workDialog.showModal === "function") workDialog.showModal();
    else workDialog.setAttribute("open", "");
    document.body.style.overflow = "hidden";
    workDialog.querySelector(".work-dialog-close").focus();
  };

  const closeWorkDialog = () => {
    if (typeof workDialog.close === "function") workDialog.close();
    else workDialog.removeAttribute("open");
  };

  workEntries.forEach((entry) => {
    const indexButton = entry.querySelector(".work-index-button");
    const mobileButton = entry.querySelector(".work-mobile-visual");
    indexButton.addEventListener("mouseenter", () => updatePreview(entry));
    indexButton.addEventListener("focus", () => updatePreview(entry));
    indexButton.addEventListener("click", () => updatePreview(entry));
    mobileButton.addEventListener("click", () => openWorkDialog(entry));
  });

  workDialog.querySelectorAll("[data-work-dialog-close]").forEach((button) => {
    button.addEventListener("click", closeWorkDialog);
  });
  workDialog.addEventListener("click", (event) => {
    if (event.target === workDialog) closeWorkDialog();
  });
  workDialog.addEventListener("close", () => {
    document.body.style.overflow = "";
  });
}

const observer = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (!entry.isIntersecting) {
      return;
    }

    entry.target.classList.add("is-visible");
    observer.unobserve(entry.target);
  });
}, {
  threshold: 0.18,
});

revealItems.forEach((item, index) => {
  item.style.setProperty("--delay", `${index * 0.08}s`);
  observer.observe(item);
});

loadInstagramPost();

async function loadInstagramPost() {
  const fallbackData = {
    url: INSTAGRAM_FALLBACK_URL,
    caption: "",
    fallbackUrl: INSTAGRAM_FALLBACK_URL,
    isFallback: true,
  };

  const embeddedData = window.__INSTAGRAM_LATEST_POST__;
  if (embeddedData && typeof embeddedData === "object") {
    renderInstagramSlots(normalizeInstagramData(embeddedData, fallbackData));
    return;
  }

  try {
    const response = await fetch(INSTAGRAM_JSON_PATH, { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`Failed to load JSON: ${response.status}`);
    }

    const data = await response.json();
    renderInstagramSlots(normalizeInstagramData(data, fallbackData));
  } catch (error) {
    renderInstagramSlots(fallbackData);
  }
}

function normalizeInstagramData(data, fallbackData) {
  const normalizedUrl = normalizeInstagramUrl(data?.url) || fallbackData.url;
  const fallbackUrl = normalizeInstagramUrl(data?.fallbackUrl) || fallbackData.url;

  return {
    url: normalizedUrl,
    caption: typeof data?.caption === "string" && data.caption.trim() ? data.caption.trim() : "",
    updatedAt: typeof data?.updatedAt === "string" ? data.updatedAt : "",
    fallbackUrl,
    isFallback: normalizedUrl === fallbackData.url,
  };
}

function renderInstagramSlots(data) {
  instagramSlots.forEach((slot) => {
    slot.innerHTML = "";
    slot.appendChild(buildInstagramCard(data, slot.dataset.variant || "section"));
  });
}

function buildInstagramCard(data, variant) {
  const wrapper = document.createElement("div");
  wrapper.className = "instagram-live-card";

  const iframe = document.createElement("iframe");
  iframe.className = "instagram-embed-frame";
  iframe.loading = "lazy";
  iframe.src = buildInstagramEmbedUrl(data.url);
  iframe.title = variant === "hero" ? "Instagram latest post hero preview" : "Instagram latest post preview";
  iframe.allow = "clipboard-write";
  wrapper.appendChild(iframe);

  if (variant !== "hero" && data.caption) {
    const caption = document.createElement("p");
    caption.className = "instagram-caption";
    caption.textContent = data.caption;
    wrapper.appendChild(caption);
  }

  if (variant !== "hero" && data.updatedAt) {
    const meta = document.createElement("p");
    meta.className = "instagram-meta";
    meta.textContent = `JSON updated: ${formatUpdatedAt(data.updatedAt)}`;
    wrapper.appendChild(meta);
  }

  const link = document.createElement("a");
  link.className = "text-link";
  link.href = data.url;
  link.target = "_blank";
  link.rel = "noreferrer";
  link.textContent = "Instagramで投稿を開く";
  wrapper.appendChild(link);

  return wrapper;
}

function buildInstagramEmbedUrl(url) {
  return `${normalizeInstagramUrl(url)}embed/captioned/`;
}

function normalizeInstagramUrl(url) {
  if (typeof url !== "string" || !url.trim()) {
    return "";
  }

  const trimmed = url.trim();
  return trimmed.endsWith("/") ? trimmed : `${trimmed}/`;
}

function formatUpdatedAt(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return new Intl.DateTimeFormat("ja-JP", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}
