from app import create_app
from dotenv import load_dotenv
import os
import click

load_dotenv()

app = create_app()


def _env_flag(name: str, default: bool = False) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


@app.cli.command("weekly-hard-cleanup")
def weekly_hard_cleanup_command():
    """Hard delete semanal para foro + objetos perdidos entregados."""
    from app.services.weekly_cleanup_service import run_weekly_hard_cleanup

    summary = run_weekly_hard_cleanup()
    click.echo(
        "weekly-hard-cleanup completed "
        f"(posts={summary['forum_posts_deleted']}, "
        f"comments={summary['forum_comments_deleted']}, "
        f"lost_found={summary['lost_found_deleted']}, "
        f"images={summary['lost_found_images_deleted']})"
    )

if __name__ == "__main__":
    # Demo stability note:
    # SSE notifications use a process-local broker. Run with a single worker/process.
    # Example: `flask run` or `gunicorn -w 1 run:app`
    app.run(debug=_env_flag("FLASK_DEBUG", default=False))
