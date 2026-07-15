

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('detections', '0008_update_stage1_model_to_efficientnet'),
    ]

    operations = [
        migrations.AddField(
            model_name='detection',
            name='predicted_plant_name',
            field=models.CharField(blank=True, default='', max_length=100),
        ),
    ]
