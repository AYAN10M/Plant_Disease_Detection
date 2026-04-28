from django.db import models
from plants.models import Plant
from diseases.models import Disease


class Detection(models.Model):

    STATUS_CHOICES = [
        ('processing',     'Processing'),
        ('success',        'Success'),
        ('low_confidence', 'Low Confidence'),
        ('not_a_plant',    'Not a Plant'),
        ('failed',         'Failed'),
    ]

    plant          = models.ForeignKey(
                       Plant,
                       on_delete=models.SET_NULL,
                       null=True,
                       related_name='detections'
                     )
    disease        = models.ForeignKey(
                       Disease,
                       on_delete=models.SET_NULL,
                       null=True, blank=True,
                       related_name='detections'
                     )
    uploaded_image = models.ImageField(upload_to='detections/uploads/')
    gradcam_image  = models.ImageField(
                       upload_to='detections/gradcam/',
                       null=True, blank=True
                     )
    confidence     = models.FloatField(default=0.0)
    status         = models.CharField(
                       max_length=20,
                       choices=STATUS_CHOICES,
                       default='processing'
                     )
    created_at     = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name        = 'Detection'
        verbose_name_plural = 'Detections'

    def __str__(self):
        return f"{self.plant} — {self.status} ({self.confidence:.0%})"