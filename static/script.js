
const uploadForm = document.getElementById("uploadForm");
const imageInput = document.getElementById("imagem");
const uploadArea = document.getElementById("uploadArea");
const uploadContent = document.getElementById("uploadContent");
const preview = document.getElementById("preview");
const selectedFile = document.getElementById("selectedFile");
const analyzeButton = document.getElementById("analyzeButton");

const errorMessage = document.getElementById("errorMessage");
const loadingMessage = document.getElementById("loadingMessage");
const results = document.getElementById("results");
const description = document.getElementById("description");
const tagsContainer = document.getElementById("tags");
const objectsContainer = document.getElementById("objects");

const MAX_SIZE = 10 * 1024 * 1024;

const allowedTypes = [
    "image/jpeg",
    "image/png",
    "image/gif",
    "image/bmp",
    "image/tiff"
];

let selectedImage = null;
let previewUrl = null;

function showError(message) {
    errorMessage.textContent = message;
    errorMessage.classList.remove("hidden");
}

function clearMessages() {
    errorMessage.classList.add("hidden");
    loadingMessage.classList.add("hidden");
}

function resetResults() {
    results.classList.add("hidden");
    description.textContent = "";
    tagsContainer.innerHTML = "";
    objectsContainer.innerHTML = "";
}

function selectImage(file) {
    clearMessages();
    resetResults();

    if (!file) {
        return;
    }

    if (!allowedTypes.includes(file.type)) {
        selectedImage = null;
        analyzeButton.disabled = true;
        showError("Formato inválido. Selecione JPG, PNG, GIF, BMP ou TIFF.");
        return;
    }

    if (file.size > MAX_SIZE) {
        selectedImage = null;
        analyzeButton.disabled = true;
        showError("A imagem ultrapassa o limite permitido de 10 MB.");
        return;
    }

    selectedImage = file;

    if (previewUrl) {
        URL.revokeObjectURL(previewUrl);
    }

    previewUrl = URL.createObjectURL(file);
    preview.src = previewUrl;

    preview.classList.remove("hidden");
    uploadContent.classList.add("hidden");

    selectedFile.textContent =
        `${file.name} • ${(file.size / 1024 / 1024).toFixed(2)} MB`;

    selectedFile.classList.remove("hidden");
    analyzeButton.disabled = false;
}

imageInput.addEventListener("change", () => {
    selectImage(imageInput.files[0]);
});

uploadArea.addEventListener("dragover", (event) => {
    event.preventDefault();
    uploadArea.classList.add("dragover");
});

uploadArea.addEventListener("dragleave", () => {
    uploadArea.classList.remove("dragover");
});

uploadArea.addEventListener("drop", (event) => {
    event.preventDefault();
    uploadArea.classList.remove("dragover");

    const file = event.dataTransfer.files[0];

    if (file) {
        imageInput.files = event.dataTransfer.files;
        selectImage(file);
    }
});

function createTag(item) {
    const tag = document.createElement("span");
    tag.className = "tag";

    const confidence = Number(item.confianca);

    tag.textContent = Number.isFinite(confidence)
        ? `${item.nome} · ${confidence.toFixed(1)}%`
        : item.nome;

    return tag;
}

function renderItems(container, items) {
    container.innerHTML = "";

    if (!items || items.length === 0) {
        const empty = document.createElement("span");
        empty.className = "empty-result";
        empty.textContent = "Nenhum item identificado.";
        container.appendChild(empty);
        return;
    }

    items.forEach((item) => {
        container.appendChild(createTag(item));
    });
}

uploadForm.addEventListener("submit", async (event) => {
    event.preventDefault();

    clearMessages();
    resetResults();

    if (!selectedImage) {
        showError("Selecione uma imagem antes de iniciar a análise.");
        return;
    }

    const formData = new FormData();
    formData.append("imagem", selectedImage);

    analyzeButton.disabled = true;
    loadingMessage.classList.remove("hidden");

    try {
        const response = await fetch("/analisar", {
            method: "POST",
            body: formData
        });

        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.erro || "Não foi possível analisar a imagem.");
        }

        description.textContent = data.descricao ||
            "Nenhuma descrição foi gerada.";

        renderItems(tagsContainer, data.tags);
        renderItems(objectsContainer, data.objetos);

        results.classList.remove("hidden");

        results.scrollIntoView({
            behavior: "smooth",
            block: "start"
        });

    } catch (error) {
        showError(error.message || "Erro inesperado ao analisar a imagem.");

    } finally {
        loadingMessage.classList.add("hidden");
        analyzeButton.disabled = false;
    }
});
