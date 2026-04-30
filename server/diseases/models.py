from django.db import models
from plants.models import Plant


class Disease(models.Model):

    SEVERITY_CHOICES = [
        ('mild',     'Mild'),
        ('moderate', 'Moderate'),
        ('severe',   'Severe'),
    ]

    plant = models.ForeignKey(Plant, on_delete=models.CASCADE, related_name='diseases')
    name            = models.CharField(max_length=150)
    description     = models.TextField()
    cause           = models.TextField()
    symptoms        = models.TextField()
    remedy          = models.TextField()
    prevention      = models.TextField(blank=True)
    severity        = models.CharField(
                        max_length=10,
                        choices=SEVERITY_CHOICES,
                        default='moderate'
                      )
    affected_parts  = models.CharField(max_length=200, blank=True)  # leaf, stem, root
    disease_image   = models.ImageField(upload_to='diseases/', null=True, blank=True)
    created_at      = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ['plant', 'name']

    def __str__(self):
        return f"{self.plant.name} — {self.name}"