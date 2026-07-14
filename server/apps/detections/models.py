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

    plant = models.ForeignKey(
        Plant, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='detections',
    )
    disease = models.ForeignKey(
        Disease, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='detections',
    )

    predicted_plant_name = models.CharField(max_length=100, blank=True, default='')

    uploaded_image      = models.ImageField(upload_to='detections/uploads/')
    plant_gradcam_image = models.ImageField(upload_to='detections/gradcam_plant/', null=True, blank=True)
    gradcam_image       = models.ImageField(upload_to='detections/gradcam_disease/', null=True, blank=True)

    plant_confidence = models.FloatField(default=0.0)
    plant_scores     = models.JSONField(default=list, blank=True)
    confidence       = models.FloatField(default=0.0)
    disease_scores   = models.JSONField(default=list, blank=True)
    advice           = models.TextField(blank=True)

    stage1_latency_ms        = models.FloatField(default=0.0)
    stage2_latency_ms        = models.FloatField(default=0.0)
    preprocessing_latency_ms = models.FloatField(default=0.0)
    total_latency_ms         = models.FloatField(default=0.0)

    stage1_model = models.CharField(max_length=30, default="EfficientNet")
    stage2_model = models.CharField(max_length=30, default="MobileNetV2")

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='processing')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering            = ['-created_at']
        verbose_name        = 'Detection'
        verbose_name_plural = 'Detections'

    def __str__(self) -> str:
        return f"{self.plant} — {self.status} ({self.confidence:.0%})"