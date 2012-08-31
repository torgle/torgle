from django.db import models

class Sites(models.Model):
    url          = models.TextField()
    links_to     = models.TextField()
    linked_from  = models.TextField()
    last_checked = models.IntegerField()
    content      = models.TextField()
    searchable   = models.TextField()
