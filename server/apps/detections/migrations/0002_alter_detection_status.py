

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('detections', '0001_initial'),
    ]

    operations = [
        migrations.AlterField(
            model_name='detection',
            name='status',
            field=models.CharField(choices=[('processing', 'Processing'), ('success', 'Success'), ('low_confidence', 'Low Confidence'), ('not_a_plant', 'Not a Plant'), ('failed', 'Failed')], default='processing', max_length=20),
        ),
    ]
