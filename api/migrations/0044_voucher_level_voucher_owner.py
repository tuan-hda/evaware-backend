# Generated by Django 4.2.1 on 2023-07-02 10:52

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('api', '0043_rename_depth_product_length'),
    ]

    operations = [
        migrations.AddField(
            model_name='voucher',
            name='level',
            field=models.IntegerField(default=0),
        ),
        migrations.AddField(
            model_name='voucher',
            name='owner',
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='vouchers', related_query_name='voucher', to=settings.AUTH_USER_MODEL),
        ),
    ]
