from django.db import models


class TrackingModel(models.Model):
    """
    Lớp cơ sở cho các model theo dõi thời gian tạo và cập nhật.

    Thuộc tính:
        created_at (DateTimeField): Thời điểm tạo
        updated_at (DateTimeField): Thời điểm cập nhật

    Meta:
        abstract = True: Lớp trừu tượng không tạo bảng trong cơ sở dữ liệu.
        ordering = ('created_at',): Sắp xếp theo thời gian tạo.

    """
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True
        ordering = ('created_at',)


class SoftDeleteManager(models.Manager):
    """
    Lớp quản lý để lấy các bản ghi chưa bị xóa mềm.

    Phương thức:
        get_queryset(): Lấy câu truy vấn queryset chưa bị soft delete.

    """

    def get_queryset(self):
        return super().get_queryset().filter(is_deleted=False)


class SoftDeleteModel(models.Model):
    """
    Lớp cơ sở cho các model hỗ trợ soft delete

    Thuộc tính:
        is_deleted (BooleanField): Trạng thái xóa mềm
        objects (Manager): Đối tượng quản lý mặc định.
        undeleted_objects (SoftDeleteManager): Đối tượng quản lý lấy các bản ghi chưa bị xóa.

    Phương thức:
        soft_delete(): Xóa mềm
        restore(): Khôi phục đã xóa.

    Meta:
        abstract = True: Lớp trừu tượng không tạo bảng trong cơ sở dữ liệu.

    """
    is_deleted = models.BooleanField(default=False)
    objects = models.Manager()
    undeleted_objects = SoftDeleteManager()

    def soft_delete(self):
        self.is_deleted = True
        self.save()

    def restore(self):
        self.is_deleted = False
        self.save()

    class Meta:
        abstract = True
