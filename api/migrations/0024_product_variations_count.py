# Generated by Django 4.2.1 on 2023-05-30 07:05

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0023_category_is_deleted'),
    ]

    operations = [
        migrations.AddField(
            model_name='product',
            name='variations_count',
            field=models.IntegerField(blank=True, default=0, null=True),
        ),
    ]
