

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('detections', '0007_update_stage1_model_default'),
    ]

    operations = [
        migrations.AlterField(
            model_name='detection',
            name='stage1_model',
            field=models.CharField(default='EfficientNet', max_length=30),
        ),
    ]
