# Generated by Django 4.2.1 on 2023-05-29 13:44

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0009_alter_category_options_alter_order_options_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='variation',
            name='is_deleted',
            field=models.BooleanField(default=False),
        ),
    ]
