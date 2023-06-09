# Generated by Django 4.2.1 on 2023-05-29 08:31

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0004_order_variation_orderdetail'),
    ]

    operations = [
        migrations.AlterField(
            model_name='variation',
            name='product',
            field=models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='variations', related_query_name='variation', to='api.product'),
        ),
    ]
