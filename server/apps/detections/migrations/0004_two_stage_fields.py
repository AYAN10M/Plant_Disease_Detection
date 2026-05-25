from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("detections", "0003_add_healthy_status"),
    ]

    operations = [
        # ── Stage-1 Grad-CAM field ─────────────────────────────────────────
        migrations.AddField(
            model_name="detection",
            name="plant_gradcam_image",
            field=models.ImageField(
                blank=True, null=True, upload_to="detections/gradcam_plant/"
            ),
        ),
        # ── Stage-1 confidence & all-class scores ─────────────────────────
        migrations.AddField(
            model_name="detection",
            name="plant_confidence",
            field=models.FloatField(default=0.0),
        ),
        migrations.AddField(
            model_name="detection",
            name="plant_scores",
            field=models.JSONField(blank=True, default=list),
        ),
        # ── Stage-2 all-class scores ───────────────────────────────────────
        migrations.AddField(
            model_name="detection",
            name="disease_scores",
            field=models.JSONField(blank=True, default=list),
        ),
        # ── Treatment advice ───────────────────────────────────────────────
        migrations.AddField(
            model_name="detection",
            name="advice",
            field=models.TextField(blank=True),
        ),
        # ── Rename gradcam upload_to (keep field name for compat) ──────────
        migrations.AlterField(
            model_name="detection",
            name="gradcam_image",
            field=models.ImageField(
                blank=True, null=True, upload_to="detections/gradcam_disease/"
            ),
        ),
        # ── Extend status choices ──────────────────────────────────────────
        migrations.AlterField(
            model_name="detection",
            name="status",
            field=models.CharField(
                choices=[
                    ("processing",     "Processing"),
                    ("success",        "Success"),
                    ("healthy",        "Healthy"),
                    ("low_confidence", "Low Confidence"),
                    ("not_recognized", "Plant Not Recognized"),
                    ("no_model",       "No Disease Model Available"),
                    ("not_a_plant",    "Not a Plant"),
                    ("failed",         "Failed"),
                ],
                default="processing",
                max_length=20,
            ),
        ),
    ]
