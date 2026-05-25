import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ('diseases', '0001_initial'),
        ('plants', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='Detection',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('uploaded_image', models.ImageField(upload_to='detections/uploads/')),
                ('gradcam_image', models.ImageField(blank=True, null=True, upload_to='detections/gradcam/')),
                ('confidence', models.FloatField(default=0.0)),
                ('status', models.CharField(
                    choices=[
                        ('processing',     'Processing'),
                        ('success',        'Success'),
                        ('low_confidence', 'Low Confidence'),
                        ('failed',         'Failed'),
                    ],
                    default='processing',
                    max_length=20,
                )),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('disease', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='detections', to='diseases.disease')),
                ('plant', models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='detections', to='plants.plant')),
            ],
            options={
                'ordering': ['-created_at'],
                'verbose_name': 'Detection',
                'verbose_name_plural': 'Detections',
            },
        ),
    ]
