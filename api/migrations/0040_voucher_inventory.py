# Generated by Django 4.2.1 on 2023-06-14 12:03

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0039_rename_composition_product_material'),
    ]

    operations = [
        migrations.AddField(
            model_name='voucher',
            name='inventory',
            field=models.IntegerField(default=0),
        ),
    ]