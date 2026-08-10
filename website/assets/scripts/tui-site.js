(() => {
  const skinKey = "flyology-tui-preview-skin";
  const skinLabels = {
    "charm-default": "Charm",
    "charm-dark": "Charm dark",
    "charm-light": "Charm light",
    "turbo-vision": "Turbo Vision"
  };

  const setSkin = (root, skin) => {
    const image = root.querySelector("[data-skin-image]");
    const source = image?.dataset[`src${skin
      .split("-").map((part) => part[0].toUpperCase() + part.slice(1)).join("")}`];
    if (!image || !source) return;
    image.src = source;
    image.alt = image.alt.replace(
      /rendered in the .+ skin$/,
      `rendered in the ${skinLabels[skin]} skin`
    );
    root.querySelectorAll("[data-skin-choice]").forEach((button) => {
      button.setAttribute("aria-pressed", String(button.dataset.skinChoice === skin));
    });
    const current = root.querySelector("[data-skin-current]");
    if (current) current.textContent = skinLabels[skin];
  };

  document.querySelectorAll("[data-skin-preview]").forEach((root) => {
    const stored = localStorage.getItem(skinKey);
    if (stored && skinLabels[stored]) setSkin(root, stored);
    root.addEventListener("click", (event) => {
      const button = event.target.closest("[data-skin-choice]");
      if (!button) return;
      const skin = button.dataset.skinChoice;
      localStorage.setItem(skinKey, skin);
      document.querySelectorAll("[data-skin-preview]")
        .forEach((preview) => setSkin(preview, skin));
    });
  });

  const search = document.querySelector("[data-component-search]");
  if (search) {
    const items = [...document.querySelectorAll("[data-component-item]")];
    const groups = [...document.querySelectorAll("[data-component-group]")];
    const count = document.querySelector("[data-component-count]");
    const empty = document.querySelector("[data-component-empty]");
    const filter = () => {
      const query = search.value.trim().toLowerCase();
      let visible = 0;
      items.forEach((item) => {
        const match = !query || item.dataset.search.includes(query);
        item.hidden = !match;
        if (match) visible += 1;
      });
      groups.forEach((group) => {
        group.hidden = !group.querySelector("[data-component-item]:not([hidden])");
      });
      count.textContent = `${visible} component${visible === 1 ? "" : "s"}`;
      empty.hidden = visible !== 0;
    };
    search.addEventListener("input", filter);
  }
})();
