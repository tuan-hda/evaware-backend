# Generated by Django 4.2.1 on 2023-06-11 04:10

import django.contrib.postgres.fields
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0032_review_img_urls'),
    ]

    operations = [
        migrations.AlterField(
            model_name='review',
            name='img_urls',
            field=django.contrib.postgres.fields.ArrayField(base_field=models.TextField(default=''), default=[], size=None),
        ),
    ]
