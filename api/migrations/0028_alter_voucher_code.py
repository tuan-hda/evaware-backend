# Generated by Django 4.2.1 on 2023-05-30 09:57

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0027_voucher_code'),
    ]

    operations = [
        migrations.AlterField(
            model_name='voucher',
            name='code',
            field=models.CharField(error_messages={'unique': 'A voucher with that code already exists.'}, max_length=30, unique=True),
        ),
    ]
