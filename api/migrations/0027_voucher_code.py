# Generated by Django 4.2.1 on 2023-05-30 09:09

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0026_voucher_order_shipping_date_order_voucher'),
    ]

    operations = [
        migrations.AddField(
            model_name='voucher',
            name='code',
            field=models.CharField(default=0, max_length=30),
            preserve_default=False,
        ),
    ]
