# Generated by Django 4.2.1 on 2023-05-30 03:38

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('api', '0017_paymentprovider_payment'),
    ]

    operations = [
        migrations.AddField(
            model_name='payment',
            name='created_by',
            field=models.ForeignKey(default=0, on_delete=django.db.models.deletion.CASCADE, related_name='payments', related_query_name='payments', to=settings.AUTH_USER_MODEL),
            preserve_default=False,
        ),
    ]
