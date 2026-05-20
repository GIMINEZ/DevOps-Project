import os

from app import create_app

app = create_app()

if __name__ == "__main__":
    # 5000 est souvent pris par le Docker Registry (local-registry)
    port = int(os.environ.get("PORT", 8080))
    debug = os.environ.get("FLASK_DEBUG", "0") == "1"
    print(f"→ http://127.0.0.1:{port}")
    app.run(host="0.0.0.0", port=port, debug=debug)
