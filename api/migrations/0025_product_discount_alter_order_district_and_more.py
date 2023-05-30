# Generated by Django 4.2.1 on 2023-05-30 08:28

import django.core.validators
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0024_product_variations_count'),
    ]

    operations = [
        migrations.AddField(
            model_name='product',
            name='discount',
            field=models.IntegerField(default=0, validators=[django.core.validators.MinValueValidator(0), django.core.validators.MaxValueValidator(100)]),
        ),
        migrations.AlterField(
            model_name='order',
            name='district',
            field=models.CharField(max_length=100),
        ),
        migrations.AlterField(
            model_name='order',
            name='district_code',
            field=models.IntegerField(),
        ),
        migrations.AlterField(
            model_name='order',
            name='email',
            field=models.EmailField(max_length=254),
        ),
        migrations.AlterField(
            model_name='order',
            name='full_name',
            field=models.CharField(max_length=300),
        ),
        migrations.AlterField(
            model_name='order',
            name='phone',
            field=models.CharField(max_length=15),
        ),
        migrations.AlterField(
            model_name='order',
            name='province',
            field=models.CharField(max_length=100),
        ),
        migrations.AlterField(
            model_name='order',
            name='province_code',
            field=models.IntegerField(),
        ),
        migrations.AlterField(
            model_name='order',
            name='street',
            field=models.CharField(max_length=300),
        ),
        migrations.AlterField(
            model_name='order',
            name='total',
            field=models.IntegerField(),
        ),
        migrations.AlterField(
            model_name='order',
            name='ward',
            field=models.CharField(max_length=100),
        ),
        migrations.AlterField(
            model_name='order',
            name='ward_code',
            field=models.IntegerField(),
        ),
    ]
