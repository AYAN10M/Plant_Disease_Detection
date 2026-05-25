from django.db import models
from plants.models import Plant
from diseases.models import Disease


class Detection(models.Model):

    STATUS_CHOICES = [
        ('processing',     'Processing'),
        ('success',        'Success'),
        ('healthy',        'Healthy'),
        ('low_confidence', 'Low Confidence'),
        ('not_recognized', 'Plant Not Recognized'),
        ('no_model',       'No Disease Model Available'),
        ('not_a_plant',    'Not a Plant'),
        ('failed',         'Failed'),
    ]

    plant   = models.ForeignKey(
        Plant,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='detections',
    )
    disease = models.ForeignKey(
        Disease,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='detections',
    )

    # ── Uploaded image ──────────────────────────────────────────────────────
    uploaded_image = models.ImageField(upload_to='detections/uploads/')

    # ── Stage-1 Grad-CAM  (plant identification heat-map) ──────────────────
    plant_gradcam_image = models.ImageField(
        upload_to='detections/gradcam_plant/',
        null=True, blank=True,
    )

    # ── Stage-2 Grad-CAM  (disease heat-map) ───────────────────────────────
    gradcam_image = models.ImageField(
        upload_to='detections/gradcam_disease/',
        null=True, blank=True,
    )

    # ── Stage-1 scores ──────────────────────────────────────────────────────
    plant_confidence = models.FloatField(default=0.0)           # 0–1
    plant_scores     = models.JSONField(default=list, blank=True)
    # e.g. [{"name": "Apple", "confidence": 0.873}, ...]

    # ── Stage-2 scores ──────────────────────────────────────────────────────
    confidence     = models.FloatField(default=0.0)             # 0–1 (disease)
    disease_scores = models.JSONField(default=list, blank=True)
    # e.g. [{"name": "Apple Scab", "confidence": 0.912}, ...]

    # ── Treatment advice ────────────────────────────────────────────────────
    advice = models.TextField(blank=True)

    # ── Status & timestamps ─────────────────────────────────────────────────
    status     = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='processing',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering            = ['-created_at']
        verbose_name        = 'Detection'
        verbose_name_plural = 'Detections'

    def __str__(self) -> str:
        return f"{self.plant} — {self.status} ({self.confidence:.0%})"