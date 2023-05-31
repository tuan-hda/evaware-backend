# Generated by Django 4.2.1 on 2023-05-31 09:08

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('api', '0029_alter_category_img_url_alter_payment_exp_and_more'),
    ]

    operations = [
        migrations.CreateModel(
            name='UsedVoucher',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='used_vouchers', related_query_name='used_voucher', to=settings.AUTH_USER_MODEL)),
                ('voucher', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='used_vouchers', related_query_name='used_voucher', to='api.voucher')),
            ],
            options={
                'ordering': ('created_at',),
                'abstract': False,
            },
        ),
    ]
