from django.db import models
from django.conf import settings
from plants.models import Plant
from diseases.models import Disease


class Detection(models.Model):

    STATUS_CHOICES = [
        ('success',        'Success'),
        ('low_confidence', 'Low Confidence'),
        ('failed',         'Failed'),
    ]

    user           = models.ForeignKey(
                       settings.AUTH_USER_MODEL,
                       on_delete=models.CASCADE,
                       related_name='detections'
                     )
    plant          = models.ForeignKey(
                       Plant,
                       on_delete=models.SET_NULL,
                       null=True,
                       related_name='detections'
                     )
    disease        = models.ForeignKey(
                       Disease,
                       on_delete=models.SET_NULL,
                       null=True, blank=True,       # null if low confidence
                       related_name='detections'
                     )
    uploaded_image = models.ImageField(upload_to='detections/uploads/')
    gradcam_image  = models.ImageField(
                       upload_to='detections/gradcam/',
                       null=True, blank=True        # null if low confidence
                     )
    confidence     = models.FloatField(default=0.0) # e.g. 0.87 means 87%
    status         = models.CharField(
                       max_length=20,
                       choices=STATUS_CHOICES,
                       default='success'
                     )
    created_at     = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']   # newest first always

    def __str__(self):
        return f"{self.user.email} — {self.plant} — {self.status}"