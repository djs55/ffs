/*
 * Copyright (C) 2006-2009 Citrix Systems Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation; version 2.1 only. with the special
 * exception on linking described in file LICENSE.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 */
#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/fail.h>
#include <caml/unixsupport.h>

#include <sys/types.h>
#include <sys/statvfs.h>
#include <linux/fs.h> 

CAMLprim value stub_statvfs(value filename) 
{
  CAMLparam1(filename);
  CAMLlocal2(v,tmp);
  int ret;
  int i;
  struct statvfs buf;

  ret = statvfs(String_val(filename), &buf);

  if(ret == -1) uerror("statvfs", Nothing);

  tmp=caml_copy_int64(0);

  /* Allocate the thing to return and ensure each of the
         fields is set to something valid before attempting 
         any further allocations */
  v=alloc_small(11,0);
  for(i=0; i<11; i++) {
        Field(v,i)=tmp;
  }

  Field(v,0)=caml_copy_int64(buf.f_bsize);
  Field(v,1)=caml_copy_int64(buf.f_frsize);
  Field(v,2)=caml_copy_int64(buf.f_blocks);
  Field(v,3)=caml_copy_int64(buf.f_bfree);
  Field(v,4)=caml_copy_int64(buf.f_bavail);
  Field(v,5)=caml_copy_int64(buf.f_files);
  Field(v,6)=caml_copy_int64(buf.f_ffree);
  Field(v,7)=caml_copy_int64(buf.f_favail);
  Field(v,8)=caml_copy_int64(buf.f_fsid);
  Field(v,9)=caml_copy_int64(buf.f_flag);
  Field(v,10)=caml_copy_int64(buf.f_namemax);

  CAMLreturn(v);
}
