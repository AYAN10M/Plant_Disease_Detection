from django.db import models

class Plant(models.Model):
    name          = models.CharField(max_length=100, unique=True)
    scientific_name = models.CharField(max_length=150, blank=True)
    family        = models.CharField(max_length=100, blank=True)   
    description   = models.TextField()                              
    origin        = models.CharField(max_length=150, blank=True)   
    growing_season = models.CharField(max_length=100, blank=True)  
    ideal_climate  = models.TextField(blank=True)                  
    common_uses    = models.TextField(blank=True)                  
    image          = models.ImageField(upload_to='plants/', null=True, blank=True)
    created_at     = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name