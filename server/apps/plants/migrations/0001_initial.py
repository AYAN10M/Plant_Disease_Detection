

from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
    ]

    operations = [
        migrations.CreateModel(
            name='Plant',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=100, unique=True)),
                ('scientific_name', models.CharField(blank=True, max_length=150)),
                ('family', models.CharField(blank=True, max_length=100)),
                ('description', models.TextField()),
                ('origin', models.CharField(blank=True, max_length=150)),
                ('growing_season', models.CharField(blank=True, max_length=100)),
                ('ideal_climate', models.TextField(blank=True)),
                ('common_uses', models.TextField(blank=True)),
                ('image', models.ImageField(blank=True, null=True, upload_to='plants/')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
            ],
        ),
    ]
