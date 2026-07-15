

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('detections', '0004_two_stage_fields'),
        ('plants', '0001_initial'),
    ]

    operations = [
        migrations.AlterField(
            model_name='detection',
            name='plant',
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='detections', to='plants.plant'),
        ),
    ]
