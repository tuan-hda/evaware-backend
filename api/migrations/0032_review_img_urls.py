# Generated by Django 4.2.1 on 2023-06-11 00:40

import django.contrib.postgres.fields
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0031_remove_favoriteitem_variation'),
    ]

    operations = [
        migrations.AddField(
            model_name='review',
            name='img_urls',
            field=django.contrib.postgres.fields.ArrayField(base_field=models.TextField(default=''), default=[], size=None),
            preserve_default=False,
        ),
    ]