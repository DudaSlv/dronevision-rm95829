
import os
import requests

from flask import Flask, render_template, request, jsonify
from PIL import Image
from io import BytesIO

app = Flask(__name__)

app.config["MAX_CONTENT_LENGTH"] = 10 * 1024 * 1024

VISION_ENDPOINT = os.getenv("VISION_ENDPOINT", "").rstrip("/")
VISION_KEY = os.getenv("VISION_KEY", "")

ALLOWED_EXTENSIONS = {"jpg", "jpeg", "png", "gif", "bmp", "tif", "tiff"}


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/analisar", methods=["POST"])
def analisar():
    if "imagem" not in request.files:
        return jsonify({"erro": "Selecione uma imagem para análise."}), 400

    arquivo = request.files["imagem"]

    if not arquivo.filename:
        return jsonify({"erro": "Nenhuma imagem foi selecionada."}), 400

    extensao = arquivo.filename.rsplit(".", 1)[-1].lower()

    if extensao not in ALLOWED_EXTENSIONS:
        return jsonify({
            "erro": "Formato inválido. Envie JPG, PNG, GIF, BMP ou TIFF."
        }), 400

    if not VISION_ENDPOINT or not VISION_KEY:
        return jsonify({
            "erro": "O serviço Azure AI Vision não está configurado."
        }), 503

    try:
        conteudo = arquivo.read()

        if not conteudo:
            return jsonify({"erro": "O arquivo enviado está vazio."}), 400

        # Valida se o conteúdo realmente corresponde a uma imagem.
        imagem = Image.open(BytesIO(conteudo))
        imagem.verify()

        if imagem.format not in {
            "JPEG", "PNG", "GIF", "BMP", "TIFF"
        }:
            return jsonify({"erro": "Formato de imagem não suportado."}), 400

    except Exception:
        return jsonify({
            "erro": "O arquivo enviado não é uma imagem válida."
        }), 400

    url = (
        f"{VISION_ENDPOINT.rstrip('/')}/computervision/imageanalysis:analyze"
        "?api-version=2024-02-01"
        "&features=caption,tags,objects"
        "&language=en"
    )

    headers = {
        "Ocp-Apim-Subscription-Key": VISION_KEY,
        "Content-Type": "application/octet-stream"
    }

    try:
        resposta = requests.post(
            url,
            headers=headers,
            data=conteudo,
            timeout=60
        )

        if resposta.status_code == 429:
            return jsonify({
                "erro": "Limite de requisições atingido. Tente novamente."
            }), 503

        if resposta.status_code in (401, 403):
            return jsonify({
                "erro": "Falha na autenticação com o Azure AI Vision."
            }), 502

        if resposta.status_code >= 500:
            return jsonify({
                "erro": "O serviço Azure AI Vision está indisponível."
            }), 503

        if not resposta.ok:
            return jsonify({
                "erro": "Não foi possível analisar a imagem.",
                "detalhe": resposta.text[:300]
            }), 502

        dados = resposta.json()

        legenda = dados.get("captionResult", {}).get("text")
        tags = dados.get("tagsResult", {}).get("values", [])
        objetos = dados.get("objectsResult", {}).get("values", [])

        return jsonify({
            "sucesso": True,
            "descricao": legenda or "Nenhuma descrição foi gerada.",
            "tags": [
                {
                    "nome": tag.get("name"),
                    "confianca": round(tag.get("confidence", 0) * 100, 1)
                }
                for tag in tags
            ],
            "objetos": [
                {
                    "nome": obj.get("tags", [{}])[0].get("name", "Objeto"),
                    "confianca": round(
                        obj.get("tags", [{}])[0].get("confidence", 0) * 100, 1
                    )
                }
                for obj in objetos
            ]
        })

    except requests.Timeout:
        return jsonify({
            "erro": "O tempo de resposta do Azure AI Vision foi excedido."
        }), 504

    except requests.RequestException:
        return jsonify({
            "erro": "Não foi possível conectar ao Azure AI Vision."
        }), 503

    except Exception:
        app.logger.exception("Erro inesperado na análise")
        return jsonify({
            "erro": "Ocorreu um erro inesperado durante a análise."
        }), 500


@app.errorhandler(413)
def arquivo_grande(_):
    return jsonify({
        "erro": "A imagem ultrapassa o limite de 10 MB."
    }), 413


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 8000)))







