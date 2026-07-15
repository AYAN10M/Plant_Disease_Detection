

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('detections', '0006_detection_preprocessing_latency_ms_and_more'),
    ]

    operations = [
        migrations.AlterField(
            model_name='detection',
            name='stage1_model',
            field=models.CharField(default='EfficientNetV2-S', max_length=30),
        ),
    ]
