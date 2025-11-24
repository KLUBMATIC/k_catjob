let scrapperRoot = null;
let uiData = {
    xp: 0,
    level: 1,
    nextXP: null,
    shopItems: [],
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

function updateXPUI() {
    const levelLabel = $("#ui-level-label");
    const xpBar = $("#xp-bar");
    const xpText = $("#xp-text");

    const xp = uiData.xp || 0;
    const level = uiData.level || 1;
    const next = uiData.nextXP;

    if (levelLabel) levelLabel.textContent = `Level ${level}`;

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

function openUI(data) {
    uiData = uiData || {};
    uiData.xp = data.xp || 0;
    uiData.level = data.level || 1;
    uiData.nextXP = data.nextXP;
    uiData.shopItems = data.shopItems || [];

    updateXPUI();
    buildShop();
    setVisible(true);
}

function closeUI() {
    setVisible(false);
    fetch(`https://k_catjob/nui_close`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: "{}"
    });
}

window.addEventListener("message", (event) => {
    const data = event.data || {};
    if (data.action === "open") {
        openUI(data.data || {});
    }
    // jobRewards is intentionally ignored now since XP popup was removed
});

window.addEventListener("DOMContentLoaded", () => {
    scrapperRoot = document.getElementById("scrapper-ui");

    const closeBtn = document.getElementById("btn-close");
    if (closeBtn) {
        closeBtn.addEventListener("click", () => {
            closeUI();
        });
    }

    document.addEventListener("keyup", (e) => {
        if (e.key === "Escape") {
            closeUI();
        }
    });
});
