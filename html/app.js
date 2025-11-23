let scrapperRoot = null;
let currentTab = "main";
let uiData = {
    xp: 0,
    level: 1,
    nextXP: null,
    shopItems: [],
    job: { hasJob: false }
};

function $(selector) {
    return document.querySelector(selector);
}

function $all(selector) {
    return Array.from(document.querySelectorAll(selector));
}

function setVisible(visible) {
    if (!scrapperRoot) return;
    if (visible) {
        scrapperRoot.classList.remove("hidden");
    } else {
        scrapperRoot.classList.add("hidden");
    }
}

function setTab(tab) {
    currentTab = tab;

    $all(".tab-button").forEach(btn => {
        btn.classList.toggle("active", btn.dataset.tab === tab);
    });

    $all(".tab-content").forEach(panel => {
        panel.classList.toggle("active", panel.id === `tab-${tab}`);
    });
}

function updateXPUI() {
    const levelLabel = $("#ui-level-label");
    const xpBar = $("#xp-bar");
    const xpText = $("#xp-text");

    const xpLevel = $("#xp-level");
    const xpTotal = $("#xp-total");
    const xpNext = $("#xp-next");

    const xp = uiData.xp || 0;
    const level = uiData.level || 1;
    const next = uiData.nextXP;

    if (levelLabel) levelLabel.textContent = `Level ${level}`;
    if (xpLevel) xpLevel.textContent = level;
    if (xpTotal) xpTotal.textContent = xp;
    if (xpNext) xpNext.textContent = next || "Max";

    let pct = 100;
    if (next && next > 0) {
        pct = Math.min(100, Math.max(0, (xp / next) * 100));
    }
    if (xpBar) {
        xpBar.style.width = `${pct}%`;
    }
    if (xpText) {
        xpText.textContent = next ? `${xp} / ${next} XP` : `${xp} XP`;
    }
}

function buildShop() {
    const container = $("#shop-list");
    if (!container) return;

    container.innerHTML = "";

    if (!uiData.shopItems || uiData.shopItems.length === 0) {
        const empty = document.createElement("div");
        empty.className = "card-text small";
        empty.textContent = "No items available at your current level.";
        container.appendChild(empty);
        return;
    }

    uiData.shopItems.forEach(item => {
        const row = document.createElement("div");
        row.className = "shop-item";

        const iconWrap = document.createElement("div");
        iconWrap.className = "shop-icon";
        const img = document.createElement("img");
        const imgName = item.image || (item.name + ".png");
        img.src = `nui://qb-inventory/html/images/${imgName}`;
        img.alt = item.label || item.name;
        iconWrap.appendChild(img);

        const info = document.createElement("div");
        info.className = "shop-info";

        const name = document.createElement("div");
        name.className = "shop-name";
        name.textContent = item.label || item.name;

        const meta = document.createElement("div");
        meta.className = "shop-meta";

        const priceSpan = document.createElement("span");
        priceSpan.textContent = `$${item.price || 0}`;

        const levelSpan = document.createElement("span");
        levelSpan.textContent = `Lvl ${item.level || 1}+`;

        meta.appendChild(priceSpan);
        meta.appendChild(levelSpan);

        info.appendChild(name);
        info.appendChild(meta);

        const btn = document.createElement("button");
        btn.className = "btn btn-shop";
        btn.textContent = "Buy";
        btn.addEventListener("click", () => {
            fetch(`https://k_catjob/nui_buyItem`, {
                method: "POST",
                headers: { "Content-Type": "application/json; charset=UTF-8" },
                body: JSON.stringify({ name: item.name })
            });
        });

        row.appendChild(iconWrap);
        row.appendChild(info);
        row.appendChild(btn);

        container.appendChild(row);
    });
}

function updateJobUI() {
    const titleEl = $("#job-status-title");
    const bodyEl = $("#job-status-body");

    if (!titleEl || !bodyEl) return;

    const job = uiData.job || { hasJob: false };

    if (!job.hasJob) {
        titleEl.textContent = "No Active Contract";
        bodyEl.innerHTML = "Press <strong>Start Job</strong> to roll a new contract. Higher levels unlock better vehicle pools.";
        return;
    }

    const tierLabel = job.tierLabel || (job.tierIndex ? `Tier ${job.tierIndex}` : "Unknown tier");
    const modelName = job.targetModel ? job.targetModel.toUpperCase() : "Unknown model";

    titleEl.textContent = "Active Contract";
    bodyEl.innerHTML = `
        <span>Tier: <strong>${tierLabel}</strong></span><br>
        <span>Target model pool includes: <strong>${modelName}</strong></span><br>
        <span class="card-text small">Head to the marked location and look for a vehicle in this class to work under.</span>
    `;
}

function openUI(tab, data) {
    uiData = uiData || {};
    uiData.xp = data.xp || 0;
    uiData.level = data.level || 1;
    uiData.nextXP = data.nextXP;
    uiData.shopItems = data.shopItems || [];
    uiData.job = data.job || { hasJob: false };

    updateXPUI();
    buildShop();
    updateJobUI();
    setTab(tab || "main");
    setVisible(true);
}

function showJobRewardsToast(payload) {
    const root = document.getElementById("catjob-toast-root");
    if (!root) return;

    root.classList.remove("hidden");
    root.innerHTML = "";

    const card = document.createElement("div");
    card.className = "toast-card";

    const header = document.createElement("div");
    header.className = "toast-header";
    header.textContent = "Converter Job Complete";
    card.appendChild(header);

    const footer = document.createElement("div");
    footer.className = "toast-footer";
    const xp = (payload && payload.xpGained) || 0;
    const oldLevel = payload && payload.oldLevel;
    const newLevel = payload && payload.newLevel;

    let footerText = `XP gained: ${xp}`;
    if (typeof oldLevel === "number" && typeof newLevel === "number" && newLevel > oldLevel) {
        footerText += ` • Level up: ${newLevel}`;
    }
    footer.textContent = footerText;
    card.appendChild(footer);

    root.appendChild(card);

    setTimeout(() => {
        root.classList.add("hidden");
        root.innerHTML = "";
    }, 7000);
}

window.addEventListener("message", (event) => {
    const data = event.data || {};
    if (data.action === "open") {
        openUI(data.tab, data.data || {});
    } else if (data.action === "jobUpdate") {
        uiData.job = data.job || { hasJob: false };
        updateJobUI();
    } else if (data.action === "jobRewards") {
        showJobRewardsToast(data.data || {});
    }
});

function closeUI() {
    setVisible(false);
    fetch(`https://k_catjob/nui_close`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: "{}"
    });
}

window.addEventListener("DOMContentLoaded", () => {
    scrapperRoot = document.getElementById("scrapper-ui");

    const closeBtn = document.getElementById("btn-close");
    if (closeBtn) {
        closeBtn.addEventListener("click", () => {
            closeUI();
        });
    }

    $all(".tab-button").forEach(btn => {
        btn.addEventListener("click", () => {
            const tab = btn.dataset.tab;
            setTab(tab);
        });
    });

    const startBtn = document.getElementById("btn-start-job");
    if (startBtn) {
        startBtn.addEventListener("click", () => {
            fetch(`https://k_catjob/nui_startJob`, {
                method: "POST",
                headers: { "Content-Type": "application/json; charset=UTF-8" },
                body: "{}"
            });
        });
    }

    document.addEventListener("keyup", (e) => {
        if (e.key === "Escape") {
            closeUI();
        }
    });
});
