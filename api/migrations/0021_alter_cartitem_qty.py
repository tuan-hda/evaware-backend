# Generated by Django 4.2.1 on 2023-05-30 04:54

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0020_alter_payment_created_by_cartitem'),
    ]

    operations = [
        migrations.AlterField(
            model_name='cartitem',
            name='qty',
            field=models.IntegerField(default=1),
        ),
    ]
